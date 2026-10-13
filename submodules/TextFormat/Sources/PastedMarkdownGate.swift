import Foundation
import TelegramCore

/// Decides whether a `ChatInputContent` produced by parsing pasted plain text as markdown carries
/// formatting or structure that ordinary plain-text paste would NOT already produce.
///
/// Returns `false` (treat as plain, let the default paste path handle it) when the content is nothing
/// but unformatted `.body` paragraphs — CommonMark collapses single-newline soft breaks and represents
/// blank-line-separated plain text as multiple plain paragraphs, and the default paste path already
/// reproduces that. Returns `true` when any block is non-paragraph, any paragraph is a heading or a list
/// item, or any run carries a non-default inline attribute (bold/italic/mono/strike/underline/spoiler/
/// formula/entity).
public func pastedMarkdownContentIsRicherThanPlain(_ content: ChatInputContent) -> Bool {
    let plainAttributes = ChatInputInlineAttributes()
    for block in content.blocks {
        guard case let .paragraph(paragraph) = block else {
            return true
        }
        if paragraph.style != .body || paragraph.list != nil {
            return true
        }
        if paragraph.runs.contains(where: { $0.attributes != plainAttributes }) {
            return true
        }
    }
    return false
}
