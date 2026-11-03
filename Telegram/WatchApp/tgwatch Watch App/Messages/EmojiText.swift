import Foundation

extension Character {
    /// True for emoji grapheme clusters: a scalar with emoji presentation, a multi-scalar
    /// cluster led by an emoji scalar (ZWJ sequences, keycaps, skin-tone), or a flag (a pair
    /// of regional-indicator scalars). Plain ASCII digits / `#` / `*` are excluded.
    var isEmojiCharacter: Bool {
        guard let first = unicodeScalars.first else { return false }
        if first.properties.isEmojiPresentation { return true }
        if first.properties.isEmoji && unicodeScalars.count > 1 { return true }
        if (0x1F1E6...0x1F1FF).contains(first.value) { return true } // regional indicator (flags)
        return false
    }
}

/// Emoji count if `text` (trimmed) consists solely of 1...3 emoji characters; else nil.
/// Used to render short emoji-only messages as jumbo, bubble-less emoji.
func emojiOnlyCount(_ text: String) -> Int? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    var count = 0
    for ch in trimmed {
        guard ch.isEmojiCharacter else { return nil }
        count += 1
        if count > 3 { return nil }
    }
    return count
}
