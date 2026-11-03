import Foundation
import TDShim

/// Renders the preview line for a chat-list row. Pure: same inputs always produce the same output.
///
/// Order of preference:
/// 1. Draft (any `draftText`, even empty) -> "Draft: <text>".
/// 2. Recognized service content -> formatted service line (omits actor for private/secret chats).
/// 3. Last message text content -> "<senderPrefix><text>".
/// 4. Last message recognized non-text content -> short type label ("Photo", "Voice message", ...).
/// 5. Anything else -> "".
func chatPreview(_ chat: CachedChat, userNames: [Int64: String], selfUserId: Int64?) -> String {
    if let draftText = chat.draftText {
        return "Draft: \(draftText)"
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
        return senderPrefix(for: last, in: chat, userNames: userNames) + text.text.text
    case .messagePhoto:    return "Photo"
    case .messageVoiceNote: return "Voice message"
    case .messageAudio(let m): return m.audio.title.isEmpty ? "Music" : m.audio.title
    case .messageSticker(let m): return m.sticker.emoji.isEmpty ? "Sticker" : "\(m.sticker.emoji) Sticker"
    case .messageVideo:    return "Video"
    case .messageVideoNote: return "Video message"
    case .messageDocument: return "Document"
    case .messageLocation: return "Location"
    case .messageVenue(let m): return m.venue.title.isEmpty ? "Location" : m.venue.title
    case .messageContact:  return "Contact"
    case .messagePoll:     return "Poll"
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

private func senderPrefix(for message: CachedMessage, in chat: CachedChat, userNames: [Int64: String]) -> String {
    if message.isOutgoing { return "You: " }
    switch chat.type {
    case .chatTypeBasicGroup, .chatTypeSupergroup:
        if case .messageSenderUser(let u) = message.senderId,
           let firstName = userNames[u.userId],
           !firstName.isEmpty {
            return "\(firstName): "
        }
        return ""
    default:
        return ""
    }
}
