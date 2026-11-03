import Foundation

/// The private markdown-link URL that carries a custom emoji's file id between
/// the send path and the rich-message renderer. Shared by the forward
/// (compose/send) path and the reverse (copy/edit) converters so the encode and
/// decode cannot drift. Format: a markdown link `[<alt>](tg://emoji?id=<fileId>)`.
public func customEmojiMarkdownURL(fileId: Int64) -> String {
    return "tg://emoji?id=\(fileId)"
}

/// Backslash-escapes only the characters that would break a marker link's
/// display text (the `alt`): backslash, the link-text brackets, and newline.
/// Minimal by design — the forward CommonMark parser unescapes these, so the
/// alt round-trips. Shared by every site that emits a `[<alt>](tg://emoji?id=…)`
/// marker so the escaping cannot drift between encoders.
public func escapeCustomEmojiMarkdownAlt(_ string: String) -> String {
    var result = ""
    result.reserveCapacity(string.count)
    for character in string {
        switch character {
        case "\\", "[", "]", "\n":
            result.append("\\")
            result.append(character)
        default:
            result.append(character)
        }
    }
    return result
}

/// Parses the file id out of a `tg://emoji?id=<fileId>` marker URL.
/// Returns nil for any other URL (ordinary links flow through unchanged).
public func parseCustomEmojiFileId(fromMarkdownURL url: String) -> Int64? {
    let prefix = "tg://emoji?id="
    guard url.hasPrefix(prefix) else {
        return nil
    }
    return Int64(url.dropFirst(prefix.count))
}

/// Regex matching an emitted marker link: `[<alt>](tg://emoji?id=<digits>)`.
/// `alt` is captured as group 1 (any run of non-`]` chars), the file id as group 2.
private let customEmojiMarkerRegex = try? NSRegularExpression(
    pattern: "\\[([^\\]]*)\\]\\(tg://emoji\\?id=(-?\\d+)\\)",
    options: []
)

/// Reverse of the forward normalization: takes reconstructed markdown source
/// (e.g. from `markdownStringFromInstantPage`) and returns an attributed string
/// where each `tg://emoji?id=` marker link has been turned back into a live
/// `ChatTextInputAttributes.customEmoji` run (the alt text carrying a
/// `ChatTextInputTextCustomEmojiAttribute`). Everything else stays verbatim
/// markdown text. Used to populate the edit compose field so it shows the
/// animated emoji; on re-save the forward path reads the attribute's fileId back.
///
/// `file` is left nil — the renderer resolves the emoji lazily from `fileId`,
/// and the send path only needs the fileId. Known limitation: an alt containing
/// a literal `]` is not matched (emoji alts do not contain brackets).
public func chatInputTextWithReattachedCustomEmoji(_ markdown: String) -> NSAttributedString {
    let result = NSMutableAttributedString(string: markdown)
    guard let regex = customEmojiMarkerRegex else {
        return result
    }
    let matches = regex.matches(in: markdown, options: [], range: NSRange(markdown.startIndex..., in: markdown))
    // Replace from last match to first so the earlier NSRanges stay valid.
    for match in matches.reversed() {
        guard match.numberOfRanges == 3 else {
            continue
        }
        guard let altRange = Range(match.range(at: 1), in: markdown),
              let idRange = Range(match.range(at: 2), in: markdown),
              let fileId = Int64(markdown[idRange]) else {
            continue
        }
        let alt = String(markdown[altRange])
        // The attribute must ride on at least one character; use a space if the
        // alt was emitted empty (selection-copy with no alt available).
        let displayText = alt.isEmpty ? " " : alt
        let attribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: fileId, file: nil)
        let replacement = NSAttributedString(string: displayText, attributes: [ChatTextInputAttributes.customEmoji: attribute])
        result.replaceCharacters(in: match.range, with: replacement)
    }
    return result
}
