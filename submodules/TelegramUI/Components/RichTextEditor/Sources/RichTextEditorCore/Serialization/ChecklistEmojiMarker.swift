import Foundation

/// The external-share serialization for checklist items: an emoji checkbox prefix that survives
/// cross-app RTF / plain-text copy-paste (the text ballot boxes ☐/☑ render as tiny/invisible glyphs in
/// many apps; the emoji are colorful and unambiguous). This is the SINGLE source of truth for the
/// symbols + the detect/strip logic, used by every export and import site.
///
/// Known accepted limitation (per the "emoji only" design choice): a non-checklist paragraph a user
/// literally typed starting with "✅ " / "⬜ " is detected as a checklist on external paste. Rare, low-stakes.
public enum ChecklistEmojiMarker {
    public static let uncheckedMarker = "\u{2B1C}"   // ⬜ WHITE LARGE SQUARE
    public static let checkedMarker = "\u{2705}"     // ✅ WHITE HEAVY CHECK MARK

    /// The emitted prefix for a checklist item: emoji + one ASCII space.
    public static func prefix(checked: Bool) -> String {
        (checked ? checkedMarker : uncheckedMarker) + " "
    }

    /// If `text` begins with ⬜ or ✅ (each tolerating a trailing U+FE0F that combines into the emoji
    /// grapheme) followed by zero or more ASCII spaces, returns its checked state and `text` minus that
    /// ONE marker; else nil. Compares on the leading grapheme's first unicode scalar, so a VS16-combined
    /// emoji ("✅️") still matches and the whole grapheme is dropped.
    public static func strippingMarker(_ text: String) -> (checked: Bool, remainder: String)? {
        guard let firstChar = text.first, let scalar = firstChar.unicodeScalars.first else { return nil }
        let checked: Bool
        if scalar == "\u{2705}" { checked = true }
        else if scalar == "\u{2B1C}" { checked = false }
        else { return nil }
        var remainder = text.dropFirst()             // drop the whole emoji grapheme (incl. any VS16)
        while remainder.first == " " { remainder = remainder.dropFirst() }
        return (checked, String(remainder))
    }
}

/// Plain text for the EXTERNAL pasteboard rep: `blockPlainText` per block, with a checkbox emoji prefix
/// on checklist paragraphs, joined by "\n". The in-app `blockPlainText` stays marker-free.
public func externalChecklistPlainText(_ blocks: [Block]) -> String {
    blocks.map { block -> String in
        if case .paragraph(let p) = block, p.list?.marker == .checklist {
            return ChecklistEmojiMarker.prefix(checked: p.list?.checked ?? false) + blockPlainText(block)
        }
        return blockPlainText(block)
    }.joined(separator: "\n")
}
