import Foundation
import TelegramCore

/// Decides whether a `ChatInputContent` produced by parsing pasted plain text as markdown carries
/// formatting or structure that ordinary plain-text paste would NOT already produce.
///
/// Returns `false` (treat as plain, let the default paste path handle it) when the content is nothing
/// but unformatted `.body` paragraphs (an empty one included) — the default paste path already reproduces
/// blank-line-separated plain text. Returns `true` when any block is non-paragraph, any paragraph is a heading or a list
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

/// Pasted markdown parsed with `MarkdownSourceLineBreaks.keep` carries every blank line of the source as an
/// empty body paragraph. They are kept only where they read as the blank lines they were: in a host that keeps
/// them (`keepsBlankLines`, the chat composer, inline or expanded) and content that is sent as text + entities, where an empty
/// paragraph is one more "\n". Content that needs a rich message (a heading, a list, a table, …) loses them, as
/// does every paste into a host that only writes rich messages: a rich message spaces its blocks itself, so an
/// empty paragraph there would double the gap.
public func pastedMarkdownContentResolvingBlankLines(_ content: ChatInputContent, keepsBlankLines: Bool) -> ChatInputContent {
    let withoutBlankLines = ChatInputContent(schemaVersion: content.schemaVersion, blocks: content.blocks.filter { block in
        if case let .paragraph(paragraph) = block, paragraph.style == .body, paragraph.list == nil, paragraph.runs.allSatisfy({ $0.text.isEmpty }) {
            return false
        }
        return true
    })
    if keepsBlankLines && withoutBlankLines.isEntityExpressible() {
        return content
    }
    return withoutBlankLines
}
