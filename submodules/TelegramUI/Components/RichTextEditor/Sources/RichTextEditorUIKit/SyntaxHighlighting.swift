#if canImport(UIKit)
import UIKit

/// One highlighted token range in a code block. A package-local value type on purpose: the editor cannot
/// see `TextFormat`/`TelegramCore`/libprisma (its deps are `RichTextEditorCore`, `AppBundle`,
/// `MosaicLayout`, and must stay that way for `swift test` and the Demo app), so no Telegram type may
/// cross this boundary. The HOST turns (language, text) into these.
public struct RichTextSyntaxToken: Equatable {
    /// A range in the code block's text, in UTF-16 units.
    public let range: NSRange
    public let color: UIColor

    public init(range: NSRange, color: UIColor) {
        self.range = range
        self.color = color
    }
}

/// The cache key for one highlight request: a normalized language plus the exact code text.
struct CodeHighlightSpec: Hashable {
    let language: String
    let text: String
}

/// A code block's language, trimmed and lowercased, or nil when it carries none usable. **Must agree with
/// the app-side `normalizedCodeBlockLanguage`** — the editor sends the normalized value and the host keys
/// the shared cache with it, so a divergence here means every lookup misses.
func richTextNormalizedCodeLanguage(_ language: String?) -> String? {
    guard let language else { return nil }
    let normalized = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized.isEmpty ? nil : normalized
}
#endif
