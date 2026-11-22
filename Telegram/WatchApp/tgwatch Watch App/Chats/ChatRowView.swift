import SwiftUI
#if DEBUG
import TDShim
#endif

struct ChatRowView: View {
    let row: ChatRow
    var onRequestDownload: (Int) -> Void = { _ in }
    var onCancelDownload: (Int) -> Void = { _ in }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            AvatarView(
                avatar: row.avatar,
                onRequestDownload: onRequestDownload,
                onCancelDownload: onCancelDownload
            )
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(row.title)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if row.isMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if !row.preview.isEmpty {
                    Text(row.preview)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                if let date = row.lastMessageDate {
                    HStack(spacing: 4) {
                        Text(chatListTimestamp(date, now: Date()))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if row.isUnreadOutgoing {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 7, height: 7)
                                .accessibilityIdentifier("chatRow.\(row.id).unreadOutgoing")
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if row.unreadCount > 0 {
                Text("\(row.unreadCount)")
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(Capsule().fill(row.isMuted ? Color.gray : Color.accentColor))
                    .foregroundStyle(.white)
            }
        }
        .accessibilityIdentifier("chatRow.\(row.id)")
    }
}

#if DEBUG
#Preview("Unread private") {
    ChatRowView(row: ChatRow(
        id: 1,
        title: "Alice Smith",
        preview: "Hey, are you around?",
        unreadCount: 3,
        isMuted: false,
        order: 100,
        chatType: .chatTypePrivate(.init(userId: 1)),
        canSend: true,
        draftText: "",
        lastReadInboxMessageId: 0,
        lastReadOutboxMessageId: 0,
        lastMessageId: nil,
        lastMessageDate: Int(Date().timeIntervalSince1970) - 600,
        avatar: AvatarVisual(kind: .normal, initials: "AS", colorIndex: 0, photoFileId: nil, photoLocalPath: nil, mini: nil)
    ))
    .padding()
}

#Preview("Muted channel") {
    ChatRowView(row: ChatRow(
        id: 2,
        title: "iOS Dev Weekly",
        preview: "New issue: SwiftUI tips",
        unreadCount: 0,
        isMuted: true,
        order: 50,
        chatType: .chatTypeSupergroup(.init(isChannel: true, supergroupId: 9)),
        canSend: false,
        draftText: "",
        lastReadInboxMessageId: 0,
        lastReadOutboxMessageId: 0,
        lastMessageId: nil,
        lastMessageDate: Int(Date().timeIntervalSince1970) - 600,
        avatar: AvatarVisual(kind: .normal, initials: "ID", colorIndex: 3, photoFileId: nil, photoLocalPath: nil, mini: nil)
    ))
    .padding()
}

#Preview("Muted with unread") {
    ChatRowView(row: ChatRow(
        id: 3,
        title: "Swift Forums",
        preview: "12 new posts in language-evolution",
        unreadCount: 12,
        isMuted: true,
        order: 80,
        chatType: .chatTypeSupergroup(.init(isChannel: true, supergroupId: 10)),
        canSend: false,
        draftText: "",
        lastReadInboxMessageId: 0,
        lastReadOutboxMessageId: 0,
        lastMessageId: nil,
        lastMessageDate: Int(Date().timeIntervalSince1970) - 600,
        avatar: AvatarVisual(kind: .normal, initials: "SF", colorIndex: 5, photoFileId: nil, photoLocalPath: nil, mini: nil)
    ))
    .padding()
}

#Preview("Long title muted") {
    ChatRowView(row: ChatRow(
        id: 4,
        title: "Aleksandr Konstantinovich Romanov",
        preview: "let's grab lunch on Thursday around noon",
        unreadCount: 1,
        isMuted: true,
        order: 70,
        chatType: .chatTypePrivate(.init(userId: 4)),
        canSend: true,
        draftText: "",
        lastReadInboxMessageId: 0,
        lastReadOutboxMessageId: 0,
        lastMessageId: nil,
        lastMessageDate: Int(Date().timeIntervalSince1970) - 600,
        avatar: AvatarVisual(kind: .normal, initials: "AK", colorIndex: 2, photoFileId: nil, photoLocalPath: nil, mini: nil)
    ))
    .padding()
}

#Preview("Big unread") {
    ChatRowView(row: ChatRow(
        id: 5,
        title: "Family",
        preview: "Mom: don't forget to call your grandmother",
        unreadCount: 999,
        isMuted: false,
        order: 90,
        chatType: .chatTypeBasicGroup(.init(basicGroupId: 11)),
        canSend: true,
        draftText: "",
        lastReadInboxMessageId: 0,
        lastReadOutboxMessageId: 0,
        lastMessageId: nil,
        lastMessageDate: Int(Date().timeIntervalSince1970) - 600,
        avatar: AvatarVisual(kind: .normal, initials: "F", colorIndex: 5, photoFileId: nil, photoLocalPath: nil, mini: nil)
    ))
    .padding()
}

#Preview("Read unmuted") {
    ChatRowView(row: ChatRow(
        id: 6,
        title: "Bob",
        preview: "ok, see you then",
        unreadCount: 0,
        isMuted: false,
        order: 40,
        chatType: .chatTypePrivate(.init(userId: 6)),
        canSend: true,
        draftText: "",
        lastReadInboxMessageId: 0,
        lastReadOutboxMessageId: 0,
        lastMessageId: nil,
        lastMessageDate: Int(Date().timeIntervalSince1970) - 600,
        avatar: AvatarVisual(kind: .normal, initials: "B", colorIndex: 4, photoFileId: nil, photoLocalPath: nil, mini: nil)
    ))
    .padding()
}

#Preview("Unread outgoing") {
    ChatRowView(row: ChatRow(
        id: 7,
        title: "Carol",
        preview: "on my way",
        unreadCount: 0,
        isMuted: false,
        order: 95,
        chatType: .chatTypePrivate(.init(userId: 7)),
        canSend: true,
        draftText: "",
        lastReadInboxMessageId: 0,
        lastReadOutboxMessageId: 4,
        lastMessageId: 5,
        lastMessageDate: Int(Date().timeIntervalSince1970) - 120,
        avatar: AvatarVisual(kind: .normal, initials: "C", colorIndex: 1, photoFileId: nil, photoLocalPath: nil, mini: nil),
        isUnreadOutgoing: true
    ))
    .padding()
}
#endif
