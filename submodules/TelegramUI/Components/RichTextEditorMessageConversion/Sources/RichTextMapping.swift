import Foundation
import TelegramCore
import TextFormat
import RichTextEditorCore

/// Map a single text run to inline `RichText`, applying its character attributes as nested wrappers.
func richText(from run: TextRun) -> RichText? {
    let attributes = run.attributes
    var result: RichText
    // FIRST, before every other leaf: a button run's text is a bare `U+FFFC`, so without this arm it
    // falls through to `.plain(run.text)` and the pill is emitted as an invisible placeholder. This is
    // an if-let chain, not an exhaustive switch, so the compiler cannot catch a missing arm here.
    if let button = attributes.button {
        result = .textButton(InstantPageButton(
            text: richText(from: button.label),
            action: replyMarkupButtonAction(from: button.action),
            color: replyMarkupColor(from: button.color),
            isLink: button.isLink
        ))
    } else if let formula = attributes.formula {
        result = .formula(latex: formula)
    } else if let emoji = attributes.emoji {
        // v1: custom emoji has no backing file here — emit its alt text as plain text.
        let alt = emoji.altText ?? ""
        if alt.isEmpty {
            return nil
        }
        result = .plain(alt)
    } else if run.text.isEmpty {
        return nil
    } else {
        result = .plain(run.text)
    }
    if attributes.inlineCode {
        result = .fixed(result)
    }
    if attributes.strikethrough {
        result = .strikethrough(result)
    }
    if attributes.underline {
        result = .underline(result)
    }
    if attributes.italic {
        result = .italic(result)
    }
    if attributes.bold {
        result = .bold(result)
    }
    if attributes.highlight != nil {
        result = .marked(result)
    }
    if let link = attributes.link {
        // The editor keeps mentions and dates as `tg://user?id=` / `tg://timestamp?t=` links
        // (`MentionDateMarkers`); they go out as a mention and a date, not as links, as from the composer
        // (`ChatInputContentInstantPage`, which nests the styles outside them). A mention marker is always a
        // user's, by its raw id.
        switch classifyChatLink(link) {
        case let .mention(peerId):
            result = .textMentionName(text: result, peerId: peerId.id._internalGetInt64Value())
        case let .date(date):
            result = .textDate(text: result, date: date, format: nil)
        case let .url(url):
            result = .url(text: result, url: url, webpageId: nil)
        }
    }
    // Outermost, as the composer's (`ChatInputContentInstantPage`): a link or mention inside a spoiler is hidden too.
    if attributes.spoiler {
        result = .textSpoiler(text: result)
    }
    return result
}

/// Map a run array to one `RichText` (`.concat` when multiple, `.empty` when none).
func richText(from runs: [TextRun]) -> RichText {
    let parts = runs.compactMap(richText(from:))
    if parts.isEmpty {
        return .empty
    }
    if parts.count == 1 {
        return parts[0]
    }
    return .concat(parts)
}
