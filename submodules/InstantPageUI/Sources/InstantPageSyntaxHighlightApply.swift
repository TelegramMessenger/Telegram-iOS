import Foundation
import UIKit
import TelegramCore
import TextFormat

/// Overlays a cached syntax highlight onto an already-built code string, keyed by (normalized language,
/// exact text) — the same key `instantPageSyntaxHighlightSpecs` writes.
///
/// A MISS leaves the string untouched: highlighting is cache-only everywhere in this app, and the first
/// paint of new code is plain until the async job lands.
///
/// **A persisted cache can outlive the text it described**, so every entity range is validated against the
/// string first and ANY out-of-bounds entity rejects the whole highlight. Applying one partially would
/// colour arbitrary spans of unrelated code. `TextFormat`'s `validatedCachedMessageSyntaxHighlight` does
/// the same job for the message path but is private to that module, so this is its equivalent rather than
/// a widened visibility.
func applyInstantPageSyntaxHighlight(to string: NSMutableAttributedString, language: String?, cache: CachedMessageSyntaxHighlight?) {
    guard let cache, let language = normalizedCodeBlockLanguage(language) else {
        return
    }
    let text = string.string
    guard let entry = cache.values[CachedMessageSyntaxHighlight.Spec(language: language, text: text)] else {
        return
    }
    let length = (text as NSString).length
    for entity in entry.entities {
        guard entity.range.lowerBound >= 0, entity.range.upperBound <= length,
              entity.range.lowerBound < entity.range.upperBound else {
            return
        }
    }
    for entity in entry.entities {
        string.addAttribute(.foregroundColor, value: UIColor(rgb: UInt32(bitPattern: entity.color)),
                            range: NSRange(location: entity.range.lowerBound,
                                           length: entity.range.upperBound - entity.range.lowerBound))
    }
}
