import Foundation
import TDShim

/// Projects a `Message.replyTo` payload into a renderable `ReplyHeader`. Pure. Returns
/// `nil` when there's no reply. See the spec at
/// `docs/superpowers/specs/2026-05-15-tgwatch-reply-headers-design.md`.
///
/// `inChatId` is the chat the host message lives in — used to decide whether the
/// source is in-chat (consult `cache`) or cross-chat (consult `origin` only).
func replyPreview(
    _ replyTo: MessageReplyTo?,
    inChatId: Int64,
    isOutgoing: Bool,
    cache: [Int64: CachedMessage],
    userNames: [Int64: String]
) -> ReplyHeader? {
    guard let replyTo else { return nil }

    switch replyTo {
    case .messageReplyToStory:
        return ReplyHeader(senderName: nil, snippet: "Story", minithumbnail: nil, isOutgoing: isOutgoing)

    case .messageReplyToMessage(let r):
        let sender = resolveSenderName(replyTo: r, inChatId: inChatId, cache: cache, userNames: userNames)
        // Resolve content: prefer TDLib's inline snippet (set when source is foreign/uncached);
        // fall back to the in-chat cached source's content (TDLib omits inline content for
        // in-chat replies by design).
        let resolvedContent: MessageContent? = r.content
            ?? (r.chatId == inChatId ? cache[r.messageId]?.content : nil)
        let snippet: String = {
            if let quote = r.quote, !quote.text.text.isEmpty {
                return quote.text.text
            }
            if let content = resolvedContent {
                return replySnippet(content)
            }
            return "Message"
        }()
        let mini = minithumbnailData(from: resolvedContent)
        return ReplyHeader(
            senderName: sender?.name,
            snippet: snippet,
            minithumbnail: mini,
            isOutgoing: isOutgoing,
            senderColorIndex: sender?.colorIndex
        )

    case .unsupported:
        return nil
    }
}

/// Same shape as `messageBody(_:)` but returns labels (not `""`) for media so the reply
/// header always has something to render.
private func replySnippet(_ content: MessageContent) -> String {
    switch content {
    case .messageText(let t):
        return t.text.text
    case .messagePhoto(let m):
        return m.caption.text.isEmpty ? "Photo" : m.caption.text
    case .messageVideo(let m):
        return m.caption.text.isEmpty ? "Video" : m.caption.text
    case .messageSticker(let m):
        return m.sticker.emoji.isEmpty ? "Sticker" : "Sticker \(m.sticker.emoji)"
    case .messageVoiceNote:
        return "Voice message"
    case .messageAudio(let m):
        return m.caption.text.isEmpty ? (m.audio.title.isEmpty ? "Music" : m.audio.title) : m.caption.text
    case .messageDocument:
        return "Document"
    case .messageLocation:
        return "Location"
    case .messageVenue(let m):
        return m.venue.title.isEmpty ? "Location" : m.venue.title
    case .messageContact:
        return "Contact"
    case .messagePoll:
        return "Poll"
    default:
        return "Message"
    }
}

private func resolveSenderName(
    replyTo r: MessageReplyToMessage,
    inChatId: Int64,
    cache: [Int64: CachedMessage],
    userNames: [Int64: String]
) -> (name: String, colorIndex: Int)? {
    if let origin = r.origin {
        switch origin {
        case .messageOriginUser(let o):
            guard let name = userNames[o.senderUserId], !name.isEmpty else { return nil }
            return (name, paletteIndex(for: o.senderUserId))
        case .messageOriginHiddenUser(let o):
            guard !o.senderName.isEmpty else { return nil }
            return (o.senderName, paletteIndex(forName: o.senderName))
        case .messageOriginChat(let o):
            guard !o.authorSignature.isEmpty else { return nil }
            return (o.authorSignature, paletteIndex(for: o.senderChatId))
        case .messageOriginChannel(let o):
            guard !o.authorSignature.isEmpty else { return nil }
            return (o.authorSignature, paletteIndex(for: o.chatId))
        case .unsupported:
            return nil
        }
    }
    // Cross-chat: skip cache lookup (we can't trust ids match).
    guard r.chatId == inChatId else { return nil }
    guard let source = cache[r.messageId] else { return nil }
    guard case .messageSenderUser(let u) = source.senderId else { return nil }
    guard let name = userNames[u.userId], !name.isEmpty else { return nil }
    return (name, paletteIndex(for: u.userId))
}

private func minithumbnailData(from content: MessageContent?) -> Data? {
    guard let content else { return nil }
    switch content {
    case .messagePhoto(let m):
        return m.photo.minithumbnail?.data
    case .messageVideo(let m):
        return m.cover?.minithumbnail?.data
    default:
        return nil
    }
}
