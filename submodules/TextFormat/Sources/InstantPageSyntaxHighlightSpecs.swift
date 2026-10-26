import Foundation
import TelegramCore

/// A code block's language, trimmed and lowercased, or nil when it carries none usable. Both the spec
/// extractor and every apply site must run a language through THIS before keying the cache, or a page
/// whose language is "Swift" stores under "swift" and looks up under "Swift" and never hits.
public func normalizedCodeBlockLanguage(_ language: String?) -> String? {
    guard let language else {
        return nil
    }
    let normalized = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized.isEmpty ? nil : normalized
}

/// Every distinct (language, code) pair in a page, in document order, for the syntax-highlight cache.
/// Recurses every block that nests blocks — INCLUDING `blockQuote`, which the private BrowserUI copy this
/// replaces did not, so code inside a quote was highlighted nowhere. `pullQuote` carries `RichText` rather
/// than blocks, so it correctly stays in `default`.
public func instantPageSyntaxHighlightSpecs(for blocks: [InstantPageBlock]) -> [CachedMessageSyntaxHighlight.Spec] {
    var specs: [CachedMessageSyntaxHighlight.Spec] = []
    var seen = Set<CachedMessageSyntaxHighlight.Spec>()

    func collect(blocks: [InstantPageBlock]) {
        for block in blocks {
            switch block {
            case let .preformatted(text, language):
                guard let language = normalizedCodeBlockLanguage(language), !text.plainText.isEmpty else {
                    continue
                }
                let spec = CachedMessageSyntaxHighlight.Spec(language: language, text: text.plainText)
                if seen.insert(spec).inserted {
                    specs.append(spec)
                }
            case let .cover(block):
                collect(blocks: [block])
            case let .postEmbed(_, _, _, _, _, blocks, _):
                collect(blocks: blocks)
            case let .collage(items, _):
                collect(blocks: items)
            case let .slideshow(items, _):
                collect(blocks: items)
            case let .details(_, blocks, _):
                collect(blocks: blocks)
            case let .list(items, _):
                for item in items {
                    if case let .blocks(blocks, _, _) = item {
                        collect(blocks: blocks)
                    }
                }
            case let .blockQuote(blocks, _, _):
                collect(blocks: blocks)
            default:
                break
            }
        }
    }

    collect(blocks: blocks)
    return specs
}
