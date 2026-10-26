import Foundation
import TelegramCore
import AccountContext
import TextFormat
import BrowserUI

/// Parses pasted plain text as CommonMark markdown (the same parser used on the rich-message send path)
/// and returns a `ChatInputContent` when the result carries formatting or structure that ordinary
/// plain-text paste would not already produce. Returns nil when:
///   - the text is unparseable / empty / iOS < 15 (`inputRichTextAttributeFromText` returns nil), or
///   - the parsed content is nothing but unformatted body paragraphs (`pastedMarkdownContentIsRicherThanPlain`).
/// Hosts convert the returned content to a `Document` (native editor) or an attributed string (legacy
/// field) with modules they already depend on.
///
/// Self-referential links are stripped BEFORE the richness gate: the markdown parser applies the GFM
/// autolink extension, so pasting a bare `https://…` (or `www.…`, or an email) yields a link run whose
/// label is the URL itself. That entity alone made the paste look "richer than plain", and the URL then
/// landed in the composer as a text link (`textUrl`) instead of as plain text the server auto-detects.
/// A genuine text link — `[label](url)`, a label that differs from its target — is untouched and still
/// classifies as rich.
func chatInputContentFromPastedMarkdown(context: AccountContext, plainText: String) -> ChatInputContent? {
    guard let attribute = inputRichTextAttributeFromText(context: context, text: plainText) else {
        return nil
    }
    let content = chatInputContentStrippingSelfReferentialLinks(chatInputContent(fromInstantPage: attribute.instantPage))
    guard pastedMarkdownContentIsRicherThanPlain(content) else {
        return nil
    }
    return content
}
