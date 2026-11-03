import Foundation
import TelegramCore

/// Whether a link's display `text` IS its own `url` — i.e. the link adds nothing a plain URL would not
/// already give, so it should paste as plain text rather than as a text link (`textUrl`) attribute.
///
/// The comparison is not a bare `==` because the producers of a link normalize the URL while leaving the
/// display text as the user wrote it. The tolerated normalizations, each observed from
/// `NSAttributedString(markdown:)` (which applies the GFM autolink extension to bare URLs):
///   - a `mailto:` scheme added to a bare email address,
///   - an `http://` / `https://` scheme added to a bare `www.` host (only when the text carries no scheme
///     of its own — `http://x` labelling `https://x` is a genuinely different destination),
///   - percent-encoding of a non-ASCII path,
///   - a trailing `/` added to a bare host.
///
/// A Telegram deep link (`tg://user?id=…`, `tg://timestamp?t=…` — the mention/date markers) never matches
/// its own display text, so those entities are unaffected.
public func chatInputLinkIsSelfReferential(text: String, url: String) -> Bool {
    let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, !url.isEmpty else {
        return false
    }

    var candidates: Set<String> = []
    var target = url
    if target.lowercased().hasPrefix("mailto:") {
        target = String(target.dropFirst("mailto:".count))
    }
    candidates.insert(target)
    if let decoded = target.removingPercentEncoding {
        candidates.insert(decoded)
    }

    var forms: Set<String> = [text, text + "/"]
    if !text.contains("://") {
        for scheme in ["http://", "https://"] {
            forms.insert(scheme + text)
            forms.insert(scheme + text + "/")
        }
    }
    return !candidates.isDisjoint(with: forms)
}

/// Clears every `.url` inline entity whose covered text is the URL itself (see
/// `chatInputLinkIsSelfReferential`), leaving the text — and every other inline attribute on the run —
/// untouched. Recurses into nested containers (block quotes, details, table cells, media captions).
///
/// Used on the PASTE path: an imported bare URL must land in the composer as plain text, so it sends as a
/// server-detected `url` entity rather than as a `textUrl` that pins the same destination. A genuine text
/// link (a label that differs from its target) is kept.
public func chatInputContentStrippingSelfReferentialLinks(_ content: ChatInputContent) -> ChatInputContent {
    var content = content
    content.blocks = content.blocks.map(chatInputBlockStrippingSelfReferentialLinks)
    return content
}

private func chatInputBlockStrippingSelfReferentialLinks(_ block: ChatInputBlock) -> ChatInputBlock {
    switch block {
    case var .paragraph(paragraph):
        paragraph.runs = strippingSelfReferentialLinks(paragraph.runs)
        return .paragraph(paragraph)
    case var .code(code):
        code.runs = strippingSelfReferentialLinks(code.runs)
        return .code(code)
    case var .media(media):
        media.caption = strippingSelfReferentialLinks(media.caption)
        return .media(media)
    case var .table(table):
        table.rows = table.rows.map { row in
            var row = row
            row.cells = row.cells.map { cell in
                var cell = cell
                cell.runs = strippingSelfReferentialLinks(cell.runs)
                return cell
            }
            return row
        }
        return .table(table)
    case var .pullQuote(pullQuote):
        pullQuote.runs = strippingSelfReferentialLinks(pullQuote.runs)
        pullQuote.author = strippingSelfReferentialLinks(pullQuote.author)
        return .pullQuote(pullQuote)
    case var .blockQuote(blockQuote):
        blockQuote.content = chatInputContentStrippingSelfReferentialLinks(blockQuote.content)
        blockQuote.author = strippingSelfReferentialLinks(blockQuote.author)
        return .blockQuote(blockQuote)
    case var .details(details):
        details.content = chatInputContentStrippingSelfReferentialLinks(details.content)
        details.title = strippingSelfReferentialLinks(details.title)
        return .details(details)
    case var .buttonRow(buttonRow):
        buttonRow.buttons = buttonRow.buttons.map { button in
            var button = button
            button.label = strippingSelfReferentialLinks(button.label)
            return button
        }
        return .buttonRow(buttonRow)
    }
}

/// The `NSAttributedString` form of `chatInputContentStrippingSelfReferentialLinks`, for the legacy composer's
/// currency: removes every `ChatTextInputAttributes.textUrl` whose covered text is the URL itself. Applied on
/// the PASTE direction only — the copy direction (`storeAttributedTextInPasteboard`) keeps whatever entities
/// the source message carried.
public func chatInputTextStrippingSelfReferentialLinks(_ string: NSAttributedString) -> NSAttributedString {
    let result = NSMutableAttributedString(attributedString: string)
    let nsString = result.string as NSString
    result.enumerateAttribute(ChatTextInputAttributes.textUrl, in: NSRange(location: 0, length: result.length), using: { value, range, _ in
        guard let attribute = value as? ChatTextInputTextUrlAttribute else {
            return
        }
        if chatInputLinkIsSelfReferential(text: nsString.substring(with: range), url: attribute.url) {
            result.removeAttribute(ChatTextInputAttributes.textUrl, range: range)
        }
    })
    return result
}

/// A link's label can be split over several runs (a formatted span inside it), so the span that must equal
/// the URL is the JOINED text of the adjacent runs sharing that same `.url` entity — not each run alone.
private func strippingSelfReferentialLinks(_ runs: [ChatInputRun]) -> [ChatInputRun] {
    var result = runs
    var index = 0
    while index < result.count {
        guard case let .url(url)? = result[index].attributes.entity else {
            index += 1
            continue
        }
        var end = index + 1
        while end < result.count, result[end].attributes.entity == .url(url) {
            end += 1
        }
        if chatInputLinkIsSelfReferential(text: result[index ..< end].map(\.text).joined(), url: url) {
            for i in index ..< end {
                result[i].attributes.entity = nil
            }
        }
        index = end
    }
    return result
}
