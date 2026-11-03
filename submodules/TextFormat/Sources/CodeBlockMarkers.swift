import Foundation

/// Builds the chat `NSAttributedString` attribute (key + value) for a code block with the given language.
/// Shared by every Document -> chat emitter (`ComposerDocumentBridge.attributedString(from:)` and
/// `EntityMessageBuilder`) so the two cannot drift; `generateChatInputTextEntities` turns it into `.Pre`.
public func chatInputCodeBlockAttribute(language: String?) -> (key: NSAttributedString.Key, value: Any) {
    return (ChatTextInputAttributes.block,
            ChatTextInputTextQuoteAttribute(kind: .code(language: language), isCollapsed: false))
}

/// The maximal contiguous ranges in `attr` carrying a `.block` attribute whose kind is `.code` (each with
/// its language). Used by `ComposerDocumentBridge.document(from:)` to carve code regions out of the chat
/// string BEFORE the per-"\n" paragraph split, so a code block's interior newlines don't fragment it.
/// Quote `.block` ranges are ignored (they stay per-line paragraphs). `enumerateAttribute` yields one
/// range per maximal run of an equal attribute value, so adjacent same-language code is already merged.
public func codeBlockRanges(in attr: NSAttributedString) -> [(range: NSRange, language: String?)] {
    var result: [(range: NSRange, language: String?)] = []
    let full = NSRange(location: 0, length: attr.length)
    attr.enumerateAttribute(ChatTextInputAttributes.block, in: full, options: []) { value, range, _ in
        guard let q = value as? ChatTextInputTextQuoteAttribute else { return }
        if case let .code(language) = q.kind {
            result.append((range, language))
        }
    }
    return result
}
