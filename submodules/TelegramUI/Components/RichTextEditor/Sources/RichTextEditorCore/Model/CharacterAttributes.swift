import Foundation

public struct CharacterAttributes: Codable, Equatable {
    public var bold: Bool
    public var italic: Bool
    public var underline: Bool
    public var strikethrough: Bool
    /// GFM `code` span. Rendered (UIKit) as a monospaced font + subtle background.
    public var inlineCode: Bool
    public var fontFamily: String?
    public var fontSize: Double?
    public var foreground: RGBAColor?
    public var highlight: RGBAColor?
    public var link: String?
    /// Baseline offset in points; positive = superscript, negative = subscript.
    public var baselineOffset: Double?
    /// An inline custom emoji. When non-nil this run's text MUST be exactly one `U+FFFC` (the emoji
    /// occupies one UTF-16 position). Has no Markdown form beyond `altText` (see the markdown-target steer).
    public var emoji: EmojiRef?
    /// An inline math formula stored as its LaTeX source. The editor may render it as a one-character
    /// atom; raw LaTeX remains the visible fallback and chat/plain-text representation.
    public var formula: String?
    /// An inline InstantPage button. When non-nil this run's text MUST be exactly one `U+FFFC` (the
    /// pill occupies one UTF-16 position), matching `emoji` and `formula`. Has no Markdown form.
    public var button: ButtonRef?
    /// Telegram-style spoiler: the run's text is hidden behind an animated "dust" overlay (UIKit) until
    /// revealed. Additive — suppresses no other attribute. No Markdown form yet (deferred to Phase 5c).
    public var spoiler: Bool

    public init(
        bold: Bool = false,
        italic: Bool = false,
        underline: Bool = false,
        strikethrough: Bool = false,
        inlineCode: Bool = false,
        fontFamily: String? = nil,
        fontSize: Double? = nil,
        foreground: RGBAColor? = nil,
        highlight: RGBAColor? = nil,
        link: String? = nil,
        baselineOffset: Double? = nil,
        emoji: EmojiRef? = nil,
        formula: String? = nil,
        button: ButtonRef? = nil,
        spoiler: Bool = false
    ) {
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.strikethrough = strikethrough
        self.inlineCode = inlineCode
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.foreground = foreground
        self.highlight = highlight
        self.link = link
        self.baselineOffset = baselineOffset
        self.emoji = emoji
        self.formula = formula
        self.button = button
        self.spoiler = spoiler
    }

    public static let plain = CharacterAttributes()

    private enum CodingKeys: String, CodingKey {
        case bold, italic, underline, strikethrough, inlineCode
        case fontFamily, fontSize, foreground, highlight, link, baselineOffset, emoji, formula, button, spoiler
    }

    // Custom decode so documents written before a field existed still load (synthesized Codable
    // throws on a missing key). Each boolean defaults false, each optional to nil. Encoding stays
    // synthesized via the declared CodingKeys.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bold = try c.decodeIfPresent(Bool.self, forKey: .bold) ?? false
        italic = try c.decodeIfPresent(Bool.self, forKey: .italic) ?? false
        underline = try c.decodeIfPresent(Bool.self, forKey: .underline) ?? false
        strikethrough = try c.decodeIfPresent(Bool.self, forKey: .strikethrough) ?? false
        inlineCode = try c.decodeIfPresent(Bool.self, forKey: .inlineCode) ?? false
        fontFamily = try c.decodeIfPresent(String.self, forKey: .fontFamily)
        fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize)
        foreground = try c.decodeIfPresent(RGBAColor.self, forKey: .foreground)
        highlight = try c.decodeIfPresent(RGBAColor.self, forKey: .highlight)
        link = try c.decodeIfPresent(String.self, forKey: .link)
        baselineOffset = try c.decodeIfPresent(Double.self, forKey: .baselineOffset)
        emoji = try c.decodeIfPresent(EmojiRef.self, forKey: .emoji)
        formula = try c.decodeIfPresent(String.self, forKey: .formula)
        button = try c.decodeIfPresent(ButtonRef.self, forKey: .button)
        spoiler = try c.decodeIfPresent(Bool.self, forKey: .spoiler) ?? false
    }
}
