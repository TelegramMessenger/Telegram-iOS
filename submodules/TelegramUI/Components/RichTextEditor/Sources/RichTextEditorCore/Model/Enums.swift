import Foundation

public enum TextAlignment: String, Codable, Equatable, CaseIterable {
    /// Leading: resolves to left in an LTR paragraph, right in an RTL one. The default for new
    /// paragraphs; the absolute cases below are explicit user overrides that win over direction.
    case natural
    case left, center, right, justified
}

public enum ParagraphStyleName: String, Codable, Equatable, CaseIterable {
    // `caption` is a render-only style (media-block captions, 15pt) — it is never offered in the style
    // picker and never persists as a paragraph style (a caption serializes as the MediaBlock's runs).
    // `pullQuote` is a render-only style (pull quote blocks, body-scale italic+center) — it never
    // persists as a paragraph style and is never offered in the style picker.
    case heading1, heading2, heading3, heading4, heading5, heading6, body, caption, pullQuote

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ParagraphStyleName(rawValue: raw) ?? .body   // old "quote" (+ any unknown) → body
    }
}

public enum ListMarker: String, Codable, Equatable, CaseIterable {
    case bullet, ordered, checklist
}

public enum MediaAlignment: String, Codable, Equatable, CaseIterable {
    case left, center, right
}

/// Whole-document writing-direction override. `.auto` lets each paragraph auto-detect its direction
/// from content (first strong character); the forced cases pin every paragraph. Persisted; auto-detected
/// per-paragraph direction is render-only and never stored.
public enum DocumentLayoutDirection: String, Codable, Equatable, CaseIterable {
    case auto, leftToRight, rightToLeft
}

/// Vertical alignment of a table cell's content within its row height. Core-native (Core is
/// TelegramCore-free); the round-trip maps it to TelegramCore's `TableVerticalAlignment`.
public enum VerticalAlignment: String, Codable, CaseIterable {
    case top, middle, bottom
}
