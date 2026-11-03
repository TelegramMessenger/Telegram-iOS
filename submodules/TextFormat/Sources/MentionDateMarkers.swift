import Foundation
import TelegramCore

/// KNOWN LIMITATION (accepted): mentions and dates are stored in the Document's shared `link` field as
/// these `tg://` marker URLs. A `textUrl` link whose string happens to equal one of these markers
/// (e.g. a `[x](tg://user?id=123)` arriving via markdown/paste/edit — the in-app link editor rejects
/// `tg://` schemes) is reinterpreted as a mention/date on a Document round-trip. This is low-probability
/// (a real text mention is a `.TextMention` entity, never a `tg://user` textUrl) and accepted rather
/// than adding dedicated model fields; revisit if it ever surfaces in practice.
///
/// Private markdown-link URL carrying a text mention's peer id between the chat composer's
/// `NSAttributedString` currency and the RichTextEditor `Document` (which stores it in the generic
/// `link` field, keeping the Core model markdown-clean). Mirrors `customEmojiMarkdownURL`. The peer id
/// is encoded as the single `Int64` the draft persistence already uses (`EnginePeer.Id.toInt64()`),
/// so the peer namespace round-trips inside it.
public func mentionMarkdownURL(peerId: EnginePeer.Id) -> String {
    return "tg://user?id=\(peerId.toInt64())"
}

/// Parses the peer id out of a `tg://user?id=<int64>` marker URL. Returns nil for any other URL
/// (ordinary links flow through unchanged).
public func parseMentionPeerId(fromURL url: String) -> EnginePeer.Id? {
    let prefix = "tg://user?id="
    guard url.hasPrefix(prefix), let raw = Int64(url.dropFirst(prefix.count)) else {
        return nil
    }
    return EnginePeer.Id(raw)
}

/// Private markdown-link URL carrying a `FormattedDate` entity's Unix timestamp through the
/// `Document.link` field (same scheme philosophy as the mention codec). This exists so dates survive
/// a Document round-trip — whether originating from an edited message / legacy draft or a future
/// native creation path.
public func dateMarkdownURL(timestamp: Int32) -> String {
    return "tg://timestamp?t=\(timestamp)"
}

/// Parses the timestamp out of a `tg://timestamp?t=<int32>` marker URL. Returns nil for any other URL.
public func parseDate(fromURL url: String) -> Int32? {
    let prefix = "tg://timestamp?t="
    guard url.hasPrefix(prefix), let value = Int32(url.dropFirst(prefix.count)) else {
        return nil
    }
    return value
}

/// The classification of a `Document.link` string when re-emitting it as a chat attribute.
public enum ChatLinkClass {
    case mention(EnginePeer.Id)
    case date(Int32)
    case url(String)
}

/// Single read-back chokepoint: decides whether a `link` is a mention, a date, or an ordinary URL.
/// Precedence is prefix-ordered so a real user URL (or a near-miss like `tg://username`) falls to `.url`.
public func classifyChatLink(_ link: String) -> ChatLinkClass {
    if let peerId = parseMentionPeerId(fromURL: link) {
        return .mention(peerId)
    }
    if let date = parseDate(fromURL: link) {
        return .date(date)
    }
    return .url(link)
}

/// Builds the chat `NSAttributedString` attribute (key + value) for a `Document.link` string. Shared by
/// every Document -> chat emitter (`ComposerDocumentBridge.attributedString(from:)` and
/// `EntityMessageBuilder`) so the mention/date/url dispatch is centralized in one place and cannot drift between the two emitters.
public func chatInputLinkAttribute(forLink link: String) -> (key: NSAttributedString.Key, value: Any) {
    switch classifyChatLink(link) {
    case let .mention(peerId):
        return (ChatTextInputAttributes.textMention, ChatTextInputTextMentionAttribute(peerId: peerId))
    case let .date(timestamp):
        return (ChatTextInputAttributes.date, ChatTextInputTextDateAttribute(date: timestamp))
    case let .url(url):
        return (ChatTextInputAttributes.textUrl, ChatTextInputTextUrlAttribute(url: url))
    }
}
