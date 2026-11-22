import Foundation
import TelegramCore

/// KNOWN LIMITATION (accepted): mentions and dates are stored in the Document's shared `link` field as
/// these `tg://` marker URLs. A `textUrl` link whose string happens to equal one of these markers
/// (e.g. a `[x](tg://user?id=123)` arriving via markdown/paste/edit — the in-app link editor rejects
/// `tg://` schemes) is reinterpreted as a mention/date on a Document round-trip. This is low-probability
/// (a real text mention is a `.TextMention` entity, never a `tg://user` textUrl) and accepted rather
/// than adding dedicated model fields; revisit if it ever surfaces in practice.
///
/// Private markdown-link URL carrying a text mention between the chat composer's `NSAttributedString`
/// currency and the RichTextEditor `Document` (which stores it in the generic `link` field, keeping the
/// Core model markdown-clean). Mirrors `customEmojiMarkdownURL`. It carries the raw user id, as Telegram's
/// own `tg://user?id=` links and a rich page's `textMentionName` do, not a packed `PeerId` (the two differ
/// for every id of 2^32 and above), so a pasted external link means the same user. Only a user can be
/// mentioned by name: any other peer has no marker, and its text stays plain.
public func mentionMarkdownURL(peerId: EnginePeer.Id) -> String? {
    let userId = peerId.id._internalGetInt64Value()
    guard peerId.namespace == Namespaces.Peer.CloudUser, isMentionableUserId(userId) else {
        return nil
    }
    return "tg://user?id=\(userId)"
}

/// A user id a `PeerId` can hold: positive, and below 2^52 (larger ones trip `PeerId`'s packing).
private func isMentionableUserId(_ userId: Int64) -> Bool {
    return userId > 0 && userId < (1 << 52)
}

/// Parses the user out of a `tg://user?id=<user id>` marker URL. Returns nil for any other URL
/// (ordinary links flow through unchanged), and for an id no user can have.
public func parseMentionPeerId(fromURL url: String) -> EnginePeer.Id? {
    let prefix = "tg://user?id="
    guard url.hasPrefix(prefix), let userId = Int64(url.dropFirst(prefix.count)), isMentionableUserId(userId) else {
        return nil
    }
    return EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(userId))
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
