import Foundation
import TDShim

/// Renders the preview line for a chat-list row. Pure: same inputs always produce the same output.
///
/// Order of preference:
/// 1. Draft (any `draftText`, even empty) -> "Draft: <text>".
/// 2. Recognized service content -> formatted service line (omits actor for private/secret chats).
/// 3. Last message text content -> "<sender>: <text>" (or just "<text>").
/// 4. Last message recognized non-text content -> short type label ("Photo", "Voice message", ...).
/// 5. Anything else -> "".
func chatPreview(_ chat: CachedChat, userNames: [Int64: String], selfUserId: Int64?) -> String {
    if let draftText = chat.draftText {
        return L("Watch.ChatList.Draft", draftText)
    }
    guard let last = chat.lastMessage else { return "" }

    if let service = serviceLineText(
        last,
        selfUserId: selfUserId,
        userNames: userNames,
        messageCache: [:],
        includeActor: shouldIncludeServiceActor(for: chat.type),
        chatType: chat.type
    ) {
        return service
    }

    switch last.content {
    case .messageText(let text):
        if let author = senderName(for: last, in: chat, userNames: userNames) {
            return L("Watch.ChatList.MessageWithAuthor", author, text.text.text)
        }
        return text.text.text
    case .messagePhoto:    return L("Message.Photo")
    case .messageVoiceNote: return L("Message.Audio")
    case .messageAudio(let m): return m.audio.title.isEmpty ? L("Watch.Message.Music") : m.audio.title
    case .messageSticker(let m): return m.sticker.emoji.isEmpty ? L("Message.Sticker") : L("Watch.ChatList.StickerWithEmoji", m.sticker.emoji)
    case .messageVideo:    return L("Message.Video")
    case .messageVideoNote: return L("Message.VideoMessage")
    case .messageDocument: return L("Watch.Message.Document")
    case .messageLocation: return L("Message.Location")
    case .messageVenue(let m): return m.venue.title.isEmpty ? L("Message.Location") : m.venue.title
    case .messageContact:  return L("Message.Contact")
    case .messagePoll:     return L("Watch.Message.Poll")
    default:               return ""
    }
}

/// Returns whether the chat-list preview should include the "{Actor} " prefix
/// for a service message. Private and secret chats omit it; basic groups,
/// supergroups, and channels include it (channels typically resolve to
/// "Someone" via the messageSenderChat actor branch).
private func shouldIncludeServiceActor(for chatType: ChatType) -> Bool {
    switch chatType {
    case .chatTypePrivate, .chatTypeSecret, .unsupported:
        return false
    case .chatTypeBasicGroup, .chatTypeSupergroup:
        return true
    }
}

/// The author shown before a text preview ("You" or a group member's first name),
/// or nil when the preview has no author prefix.
private func senderName(for message: CachedMessage, in chat: CachedChat, userNames: [Int64: String]) -> String? {
    if message.isOutgoing { return L("DialogList.You") }
    switch chat.type {
    case .chatTypeBasicGroup, .chatTypeSupergroup:
        if case .messageSenderUser(let u) = message.senderId,
           let firstName = userNames[u.userId],
           !firstName.isEmpty {
            return firstName
        }
        return nil
    default:
        return nil
    }
}
