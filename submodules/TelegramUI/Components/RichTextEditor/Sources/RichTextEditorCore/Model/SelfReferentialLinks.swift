import Foundation

/// Whether a link's display `text` IS its own `url` — i.e. the link adds nothing a plain URL would not
/// already give, so imported content should carry it as plain text rather than as a link run.
///
/// The comparison is not a bare `==` because the producers of a link normalize the URL while leaving the
/// display text as the author wrote it: a `mailto:` scheme on a bare email, an `http://`/`https://` scheme
/// on a bare `www.` host (tolerated only when the text carries no scheme of its own — `http://x` labelling
/// `https://x` is a genuinely different destination), percent-encoding of a non-ASCII path, and a trailing
/// `/` added to a bare host.
///
/// NOTE: this is deliberately duplicated from `TextFormat`'s `chatInputLinkIsSelfReferential` — Core is a
/// UIKit-free, dependency-free package and cannot import the app's modules. Keep the two rules in step.
public func linkIsSelfReferential(text: String, url: String) -> Bool {
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

public extension Document {
    /// Clears every `link` whose covered text is the URL itself (see `linkIsSelfReferential`), leaving the
    /// text — and every other character attribute — untouched.
    ///
    /// Applied when IMPORTING external content (an RTF paste): a web link whose anchor text is the URL must
    /// land in the editor as plain text, so it sends as a plain URL rather than as a text link pinning the
    /// same destination. A genuine text link — a label that differs from its target — is kept, as is
    /// anything pasted from Telegram's own fragment UTI (that never goes through an importer).
    func strippingSelfReferentialLinks() -> Document {
        var result = self
        result.blocks = result.blocks.map(blockStrippingSelfReferentialLinks)
        return result
    }
}

private func blockStrippingSelfReferentialLinks(_ block: Block) -> Block {
    switch block {
    case var .paragraph(paragraph):
        paragraph.runs = runsStrippingSelfReferentialLinks(paragraph.runs)
        return .paragraph(paragraph)
    case var .code(code):
        code.runs = runsStrippingSelfReferentialLinks(code.runs)
        return .code(code)
    case var .media(media):
        media.caption = runsStrippingSelfReferentialLinks(media.caption)
        return .media(media)
    case var .table(table):
        table.rows = table.rows.map { row in
            var row = row
            row.cells = row.cells.map { cell in
                var cell = cell
                cell.blocks = cell.blocks.map(blockStrippingSelfReferentialLinks)
                return cell
            }
            return row
        }
        return .table(table)
    case var .pullQuote(pullQuote):
        pullQuote.runs = runsStrippingSelfReferentialLinks(pullQuote.runs)
        pullQuote.author = runsStrippingSelfReferentialLinks(pullQuote.author)
        return .pullQuote(pullQuote)
    case var .blockQuote(blockQuote):
        blockQuote.children = blockQuote.children.map(blockStrippingSelfReferentialLinks)
        blockQuote.author = runsStrippingSelfReferentialLinks(blockQuote.author)
        return .blockQuote(blockQuote)
    case var .details(details):
        details.children = details.children.map(blockStrippingSelfReferentialLinks)
        details.title = runsStrippingSelfReferentialLinks(details.title)
        return .details(details)
    case var .buttonRow(buttonRow):
        buttonRow.buttons = buttonRow.buttons.map { button in
            var button = button
            button.label = runsStrippingSelfReferentialLinks(button.label)
            return button
        }
        return .buttonRow(buttonRow)
    }
}

/// A link's label can be split over several runs (a formatted span inside it), so the span that must equal
/// the URL is the JOINED text of the adjacent runs sharing that same link — not each run alone.
private func runsStrippingSelfReferentialLinks(_ runs: [TextRun]) -> [TextRun] {
    var result = runs
    var index = 0
    while index < result.count {
        guard let url = result[index].attributes.link else {
            index += 1
            continue
        }
        var end = index + 1
        while end < result.count, result[end].attributes.link == url {
            end += 1
        }
        if linkIsSelfReferential(text: result[index ..< end].map(\.text).joined(), url: url) {
            for i in index ..< end {
                result[i].attributes.link = nil
            }
        }
        index = end
    }
    return result
}
